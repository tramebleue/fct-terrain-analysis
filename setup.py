from distutils.core import setup
from Cython.Build import cythonize
from distutils.extension import Extension
from distutils.sysconfig import get_python_inc
import numpy

extensions = [
    
    Extension('terrain_analysis',
        # [ 'ta/terrain_analysis.pyx', 'ta/common.pxi', 'ta/cfilldem.pxi', 'ta/cflowdir.pxi', 'ta/cwatershed.pxi', 'ta/cstrahler.pxi', 'ta/CppTermProgress.cpp' ],
        [ 'src/ta/terrain_analysis.pyx', 'src/cpp/CppTermProgress.cpp' ],
        language='c++',
        include_dirs=[ 'src/cpp', numpy.get_include() ])
    
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

    # Extension('cfilldem2',
    #     [ 'cfilldem2.pyx', 'common.pyx', 'CppTermProgress.cpp' ],
    #     language='c++',
    #     include_dirs = [ get_python_inc(plat_specific=True), numpy.get_include() ])

]

setup(
    name = "terrain_analysis",
    ext_modules = cythonize(extensions),
    package_dir = { '' : 'src' },
    packages = [ 'vector' ]
)
