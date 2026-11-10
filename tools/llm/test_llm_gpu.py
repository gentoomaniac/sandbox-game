"""Tests of the GPU choice of llm.sh (`make test` runs them). `LLM_DRY_RUN=1 llm.sh up` prints the
container command instead of running it; the devices, CDI specs and sysfs nodes it looks at are a
fake tree in a temporary folder, so neither the machine's GPU nor podman is ever touched."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

LLM_SH = Path(__file__).with_name("llm.sh")


class FakeMachine:
    """A tree of what llm.sh looks at: no GPU until the `with_*` calls add one."""

    def __init__(self, root: Path):
        self.kfd = root / "dev" / "kfd"
        self.dri = root / "dev" / "dri"
        self.nodes = root / "sys" / "kfd" / "nodes"
        self.cdi = root / "cdi"
        for folder in (self.dri, self.nodes, self.cdi):
            folder.mkdir(parents=True)
        self.amdgpu_module = root / "sys" / "amdgpu"

    def with_nvidia(self) -> "FakeMachine":
        (self.cdi / "nvidia.yaml").write_text("kind: nvidia.com/gpu\n")
        return self

    def with_amd_driver_only(self) -> "FakeMachine":
        self.kfd.touch()
        return self

    def with_amd(self, *gfx_target_versions: int) -> "FakeMachine":
        """A GPU for each version (major * 10000 + minor * 100 + step), after the CPU's node."""
        self.with_amd_driver_only()
        (self.dri / "renderD128").touch()
        for index, version in enumerate((0, *gfx_target_versions)):
            node = self.nodes / str(index)
            node.mkdir()
            (node / "properties").write_text(f"cpu_cores_count 8\ngfx_target_version {version}\n")
        return self

    def run(self, **environment: str) -> subprocess.CompletedProcess:
        env = {
            "PATH": os.environ["PATH"],
            "CONTAINER": "podman",
            "LLM_DRY_RUN": "1",
            "LLM_CDI_DIRS": str(self.cdi),
            "LLM_KFD_DEVICE": str(self.kfd),
            "LLM_DRI_DIR": str(self.dri),
            "LLM_KFD_NODES": str(self.nodes),
            "LLM_AMDGPU_MODULE": str(self.amdgpu_module),
            **environment,
        }
        return subprocess.run(
            ["sh", str(LLM_SH), "up"], env=env, capture_output=True, text=True, timeout=30
        )


class LlmGpuChoiceTest(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.machine = FakeMachine(Path(folder.name))

    def assert_starts(self, result, label, image_suffix="", has=(), lacks=()):
        self.assertEqual(result.returncode, 0, result.stderr)
        command = result.stdout.strip().splitlines()[-1]
        self.assertIn(f"--label sandbox-game.gpu={label} ", command)
        self.assertTrue(command.endswith(f"ollama/ollama:0.35.0{image_suffix}"), command)
        for part in has:
            self.assertIn(part, command)
        for part in lacks:
            self.assertNotIn(part, command)

    def assert_fails(self, result, message):
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(message, result.stderr)
        self.assertEqual(result.stdout, "")

    def test_nvidia_gets_its_cdi_device_and_the_plain_image(self):
        result = self.machine.with_nvidia().run()
        self.assert_starts(
            result, "nvidia", has=["--device nvidia.com/gpu=all"], lacks=["kfd", "keep-groups"]
        )

    def test_amd_gets_the_rocm_image_both_devices_and_its_groups(self):
        machine = self.machine.with_amd(110000)
        result = machine.run()
        self.assert_starts(
            result,
            "amd",
            "-rocm",
            has=[f"--device {machine.kfd}", f"--device {machine.dri}", "--group-add keep-groups"],
            lacks=["HSA_OVERRIDE", "nvidia"],
        )
        self.assertIn("AMD GPU: gfx1100", result.stdout)
        self.assertNotIn("try LLM_HSA_OVERRIDE", result.stdout)

    def test_docker_adds_the_numeric_groups_of_the_devices(self):
        result = self.machine.with_amd(110000).run(CONTAINER="docker")
        self.assert_starts(result, "amd", "-rocm", lacks=["keep-groups"])
        self.assertIn("docker run -d", result.stdout)
        self.assertIn(f"--group-add {self.machine.kfd.stat().st_gid}", result.stdout)

    def test_amd_passes_the_hsa_override_on(self):
        result = self.machine.with_amd(110000).run(LLM_HSA_OVERRIDE="10.3.0")
        self.assert_starts(result, "amd", "-rocm", has=["-e HSA_OVERRIDE_GFX_VERSION=10.3.0"])

    def test_an_rdna2_card_rocm_does_not_list_gets_the_override_hint(self):
        result = self.machine.with_amd(100301).run()
        self.assert_starts(result, "amd", "-rocm", lacks=["HSA_OVERRIDE"])
        self.assertIn("AMD GPU: gfx1031", result.stdout)
        self.assertIn("try LLM_HSA_OVERRIDE=10.3.0", result.stdout)

    def test_the_rdna3_7600_gets_the_other_override_hint(self):
        result = self.machine.with_amd(110002).run()
        self.assertIn("AMD GPU: gfx1102", result.stdout)
        self.assertIn("try LLM_HSA_OVERRIDE=11.0.0", result.stdout)

    def test_a_listed_card_gets_no_hint_and_two_cards_a_warning(self):
        result = self.machine.with_amd(100300, 100300).run()
        self.assertNotIn("try LLM_HSA_OVERRIDE", result.stdout)
        self.assertIn("several AMD GPUs", result.stdout)

    def test_no_gpu_falls_back_to_the_cpu_without_a_word_about_one(self):
        result = self.machine.run()
        self.assert_starts(result, "cpu", lacks=["--device", "-rocm"])
        self.assertNotIn("AMD", result.stderr)

    def test_an_amd_driver_without_a_render_node_falls_back_to_the_cpu_and_says_why(self):
        result = self.machine.with_amd_driver_only().run()
        self.assert_starts(result, "cpu", lacks=["--device", "-rocm"])
        self.assertIn("using the CPU: no render node in", result.stderr)

    def test_nvidia_is_taken_when_both_are_usable(self):
        result = self.machine.with_nvidia().with_amd(110000).run()
        self.assert_starts(result, "nvidia")
        self.assertIn("taking NVIDIA", result.stderr)

    def test_forced_nvidia_and_amd_choose_that_one(self):
        machine = self.machine.with_nvidia().with_amd(110000)
        self.assert_starts(machine.run(LLM_GPU="nvidia"), "nvidia")
        self.assert_starts(machine.run(LLM_GPU="amd"), "amd", "-rocm")

    def test_forced_nvidia_and_amd_fail_when_the_gpu_is_not_there(self):
        self.assert_fails(self.machine.run(LLM_GPU="nvidia"), "LLM_GPU=nvidia but there is no CDI")
        self.assert_fails(self.machine.run(LLM_GPU="amd"), "LLM_GPU=amd but no ")

    def test_zero_forces_the_cpu_even_with_a_gpu(self):
        result = self.machine.with_nvidia().with_amd(110000).run(LLM_GPU="0")
        self.assert_starts(result, "cpu", lacks=["--device"])

    def test_one_takes_any_usable_gpu_or_fails(self):
        self.assert_fails(self.machine.run(LLM_GPU="1"), "LLM_GPU=1 but no GPU is usable")
        self.assert_starts(self.machine.with_amd(110000).run(LLM_GPU="1"), "amd", "-rocm")

    def test_an_unknown_choice_is_refused(self):
        self.assert_fails(self.machine.run(LLM_GPU="tpu"), "LLM_GPU must be")


if __name__ == "__main__":
    unittest.main()
