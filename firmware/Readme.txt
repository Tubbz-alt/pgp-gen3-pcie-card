This is the COB DPM top level directory.

The modules directory contains the generic modules 
that are used in multiple DPM projects.

The projects directory contains the specific design
files for each DPM project. 

The top level generic makefile 'system.mk' is contained
in this directory. 

In order to build a project go to the project's directory
and type gmake. See the  Readme.txt file in the project 
directory for more information.

A local build directory must be created in order to compile designs.
The build directory can either be a local directory or a link to 
a directory located on a scratch disk:

mkdir build
or
ln -s /u1/build build

