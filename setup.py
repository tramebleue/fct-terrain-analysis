from distutils.core import setup
from Cython.Build import cythonize
from distutils.extension import Extension
from distutils.sysconfig import get_python_inc
import numpy

extensions = [
    
    Extension('*',
        [ '*.pyx', 'CppTermProgress.cpp' ],
        language='c++',
        include_dirs=[ numpy.get_include() ])
    
    # Extension('CppTermProgress',
    #     [ 'CppTermProgress.cpp' ],
    #     language='c++',
    #     include_dirs = [ get_python_inc(plat_specific=True) ]),
    
    # Extension('cflowdir',
    #     [ 'cflowdir.pyx' ],
    #     include_dirs=[ numpy.get_include() ]),

    # Extension('cstrahler',
    #     [ 'cstrahler.pyx', 'CppTermProgress.cpp' ],
    #     language='c++',
    #     include_dirs=[ numpy.get_include() ]),

    # Extension('cwatershed',
    #     [ 'cwatershed.pyx', 'CppTermProgress.cpp' ],
    #     language='c++',
    #     include_dirs=[ numpy.get_include() ]),

    # Extension('cfilldem',
    #     [ 'cfilldem.pyx', 'CppTermProgress.cpp' ],
    #     language='c++',
    #     include_dirs = [ get_python_inc(plat_specific=True), numpy.get_include() ])

]

setup(
    name = "_filldem",
    ext_modules = cythonize(extensions),
)