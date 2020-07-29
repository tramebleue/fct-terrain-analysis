from distutils.core import setup
from Cython.Build import cythonize
from distutils.extension import Extension
from distutils.sysconfig import get_python_inc
import numpy

# Parse the version from the main module.
with open('fct/__init__.py', 'r') as f:
    for line in f:
        if line.find("__version__") >= 0:
            version = line.split("=")[1].strip().strip('"').strip("'")
            break

open_kwds = {'encoding': 'utf-8'}

with open('VERSION.txt', 'w', **open_kwds) as f:
    f.write(version)

extensions = [
    
    Extension('fct.terrain_analysis',
        # [ 'ta/terrain_analysis.pyx', 'ta/common.pxi', 'ta/cfilldem.pxi', 'ta/cflowdir.pxi', 'ta/cwatershed.pxi', 'ta/cstrahler.pxi', 'ta/CppTermProgress.cpp' ],
        [ 'cython/terrain_analysis.pyx' ],
        language='c++',
        include_dirs=[ 'src/cpp', numpy.get_include() ])
]

setup(
    name = "fct_terrain_analysis",
    version=version,
    ext_modules = cythonize(extensions)
)
