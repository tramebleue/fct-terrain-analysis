#include "CppTermProgress.h"
#include <stdio.h>

using namespace std;

CppTermProgress::CppTermProgress():
	total(0),
	count(0),
	last_tick(-1) {}

CppTermProgress::CppTermProgress(long total):
	total(total),
	count(0),
	last_tick(-1) {}

CppTermProgress::CppTermProgress(const CppTermProgress& other):
	total(other.total),
	count(other.count),
	last_tick(other.last_tick) {}

CppTermProgress::~CppTermProgress() {}

void CppTermProgress::update(int n) {

	count += n;
	int tick = (int) ((1.0 * count / total) * 40.0);
	
	if (tick > last_tick) {
		last_tick = tick;
		print_progress(tick);
	}

}

void CppTermProgress::write(char* msg) {

	clear_progress();
	fprintf(stdout, "\r%s\n", msg);
	print_progress(last_tick);

	fflush(stdout);

}

void CppTermProgress::close() {

	clear_progress();
	fprintf(stdout, "\r");

	fflush(stdout);

}

void CppTermProgress::print_progress(int tick) {

	fprintf(stdout, "\r");

	for (int i=0; i<tick; i++) {
		if (i % 4 == 0) {
			fprintf(stdout, "%d", (i / 4) * 10);
		} else {
			fprintf(stdout, ".");
		}
	}

	fflush(stdout);

}

void CppTermProgress::clear_progress() {

	fprintf(stdout, "\r");

	for (int i=0; i<last_tick; i++) {
		if (i % 4 == 0) {
			fprintf(stdout, "  ");
		} else {
			fprintf(stdout, " ");
		}
	}

}