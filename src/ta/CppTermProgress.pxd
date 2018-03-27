cdef extern from "CppTermProgress.h" nogil:

	cdef cppclass CppTermProgress:

		CppTermProgress() except +
		CppTermProgress(long total) except +
		void update(int n)
		void write(char* msg)
		void close()