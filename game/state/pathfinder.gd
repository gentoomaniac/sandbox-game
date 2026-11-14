class_name Pathfinder
extends RefCounted
## Runs the searches (PathSearch) for the villagers, each as a task of its own on a worker thread,
## and gives their results back on the main thread. A search reads only what does not change (see
## TravelView), so it is the only one to touch itself while it runs; the Pathfinder reads its state
## once the task is done, and so does whoever queued it, through `is_finished`.
##
## A search that has to wait for a tile that is not known (a mask not made yet) comes back from its
## task as WAITING, never blocks the pool: it is parked until its `provide` Callable says that what
## it waits for is there, and is then run again. At most `max_tasks` run at once, so a burst of
## searches does not fill the pool; the others queue, the oldest first. `tick` is called once a
## frame, on the main thread.
##
## How it all works: design/tech/pathfinding.md.


## A search with what it needs to go on.
class Job:
	extends RefCounted
	var search: PathSearch
	## `() -> bool` on the main thread: gives the search what it waits for, and says whether that is
	## all of it. Without one a waiting search is run again at once.
	var provide: Callable
	var task_id := -1
	var is_dropped := false


## How many searches run at once, at the most. Npcs changes it with its rules.
var max_tasks: int

var _queued: Array[Job] = []
var _running: Array[Job] = []
var _parked: Array[Job] = []
## The searches that are over and not taken yet.
var _finished: Dictionary[PathSearch, bool] = {}


func _init(tasks: int) -> void:
	max_tasks = tasks


func _notification(what: int) -> void:
	# A task holds its search, which must not be freed while it runs.
	if what == NOTIFICATION_PREDELETE:
		for job in _running:
			WorkerThreadPool.wait_for_task_completion(job.task_id)


## Queues a search. `provide` is described at `Job`.
func queue(search: PathSearch, provide := Callable()) -> void:
	if search.is_over():
		_finished[search] = true
		return
	var job := Job.new()
	job.search = search
	job.provide = provide
	if search.state == PathSearch.State.WAITING:
		_parked.append(job)
	else:
		_queued.append(job)


## Whether the search is over and its result can be read. The state of a search that is not is not
## to be read: a worker may be writing it.
func is_finished(search: PathSearch) -> bool:
	return _finished.has(search)


## Hands over the result of a finished search: it is not kept any more.
func take(search: PathSearch) -> void:
	_finished.erase(search)


## Takes a search out, whether it is done or not: its result is never looked at. One that is
## running goes on until its task ends, and is then forgotten.
func drop(search: PathSearch) -> void:
	_finished.erase(search)
	for jobs in [_queued, _parked]:
		for job: Job in jobs:
			if job.search == search:
				jobs.erase(job)
				return
	for job in _running:
		if job.search == search:
			job.is_dropped = true


## How many searches run on a worker now.
func running() -> int:
	return _running.size()


## How many searches are not over yet (the dropped ones that still run are not counted).
func waiting() -> int:
	var count := _queued.size() + _parked.size()
	for job in _running:
		count += 0 if job.is_dropped else 1
	return count


## Collects the tasks that are done, gives the parked searches what they wait for and starts as
## many as `max_tasks` allows.
func tick() -> void:
	for job in _running.duplicate():
		if WorkerThreadPool.is_task_completed(job.task_id):
			_collect(job)
	for job in _parked.duplicate():
		if not job.provide.is_valid() or job.provide.call():
			_parked.erase(job)
			_queued.append(job)
	while _running.size() < max_tasks and not _queued.is_empty():
		var job: Job = _queued.pop_front()
		job.task_id = WorkerThreadPool.add_task(_run.bind(job.search))
		_running.append(job)


## Waits for every search to be over, for the tests and for a skip of time.
func wait_for_all() -> void:
	while waiting() > 0:
		for job in _running.duplicate():
			WorkerThreadPool.wait_for_task_completion(job.task_id)
			_collect(job)
		tick()


## Runs on the worker.
func _run(search: PathSearch) -> void:
	search.step(1 << 30)


func _collect(job: Job) -> void:
	WorkerThreadPool.wait_for_task_completion(job.task_id)
	_running.erase(job)
	if job.is_dropped:
		return
	if job.search.is_over():
		_finished[job.search] = true
	else:
		_parked.append(job)
