from libcpp.queue cimport priority_queue
from libcpp.pair cimport pair
from libcpp.stack cimport stack

ctypedef pair[long, long] Cell
ctypedef stack[Cell] CellStack
ctypedef pair[float, Cell] QueueEntry
ctypedef priority_queue[QueueEntry] CellQueue