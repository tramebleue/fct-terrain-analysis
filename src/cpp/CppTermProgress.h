#pragma once

class CppTermProgress {

	private:
		
		long total;
		long count;
		int  last_tick;

		void print_progress(int tick);
		void clear_progress();

	public:

		CppTermProgress();
		CppTermProgress(const CppTermProgress& other);
		CppTermProgress(long total);
		~CppTermProgress();

		void update(int n);
		void write(char* msg);
		void close();

};