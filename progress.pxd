cdef class TermProgress:

    cdef long total
    cdef long count
    cdef int  last_tick

    cpdef void update(self, int n)
    cpdef void write(self, unicode msg)
    cpdef void close(self)
    cpdef print_progress(self, int tick)
    cpdef clear_progress(self)
