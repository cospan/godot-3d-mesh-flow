extends Node

class_name ThreadSafeQueue

var m_queue:Array
var m_queue_mutex:Mutex
var m_queue_sem:Semaphore

signal NEW_DATA

# Called when the node enters the scene tree for the first time.
func _init():
    m_queue.clear()
    m_queue_mutex = Mutex.new()
    m_queue_sem = Semaphore.new()

func is_empty():
    var empty:bool = true
    m_queue_mutex.lock()
    empty = m_queue.is_empty()
    m_queue_mutex.unlock()
    return empty


func push(v):
    m_queue_mutex.lock()
    m_queue.push_back(v)
    m_queue_sem.post()
    m_queue_mutex.unlock()
    self.emit_signal("NEW_DATA")

func try_pop():
    var v
    var rv = m_queue_sem.try_wait()
    if not rv:
        return null
    m_queue_mutex.lock()
    v = m_queue.pop_front()
    m_queue_mutex.unlock()
    return v

func pop():
    var v
    m_queue_sem.wait()
    m_queue_mutex.lock()
    v = m_queue.pop_front()
    m_queue_mutex.unlock()
    return v




