from sys import stdout

class TermProgress(object):

    def __init__(self, total):
        
        self.total = total
        self.count = 0
        self.last_tick = -1

    def write(self, msg):

        self.clear_progress()
        stdout.write('\r')
        stdout.write(msg)
        stdout.write('\n')
        self.print_progress(self.last_tick)

    def update(self, n=1):
        
        self.count = self.count + n
        tick = int((1.0 * self.count / self.total) * 40.0)
        if tick > self.last_tick:
            self.last_tick = tick
            self.print_progress(tick)

    def clear_progress(self):
        
        stdout.write('\r')
        for i in range(self.last_tick + 1):
            if i % 4 == 0:
                stdout.write('  ')
            else:
                stdout.write(' ')

    def print_progress(self, tick):
        
        stdout.write('\r')
        for i in range(tick + 1):
            if i % 4 == 0:
                stdout.write(str((i / 4) * 10))
            else:
                stdout.write('.')

        stdout.flush()

    def close(self):

        self.clear_progress()
        stdout.write('\r')
        stdout.flush()