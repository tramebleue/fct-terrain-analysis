from sys import stdout

cdef class TermProgress:

    def __cinit__(self, long total):
        
        self.total = total
        self.count = 0
        self.last_tick = -1

    cpdef void write(self, unicode msg):

        self.clear_progress()
        stdout.write('\r')
        stdout.write(msg)
        stdout.write('\n')
        self.print_progress(self.last_tick)

    cpdef void update(self, int n):
        
        cdef int tick
        
        self.count = self.count + n
        tick = int((1.0 * self.count / self.total) * 40.0)
        if tick > self.last_tick:
            self.last_tick = tick
            self.print_progress(tick)

    cpdef clear_progress(self):

        cdef int i
        
        stdout.write('\r')
        for i in range(self.last_tick + 1):
            if i % 4 == 0:
                stdout.write('  ')
            else:
                stdout.write(' ')

    cpdef print_progress(self, int tick):
        
        cdef int i
        
        stdout.write('\r')
        for i in range(tick + 1):
            if i % 4 == 0:
                stdout.write(str((i / 4) * 10))
            else:
                stdout.write('.')

        stdout.flush()

    cpdef void close(self):

        self.clear_progress()
        stdout.write('\r')
        stdout.flush()