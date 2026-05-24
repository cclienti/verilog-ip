MAKEFLAGS := -j $(shell lscpu -x -p=CPU |grep -v ^\# |wc -l)

ODG_FILES = $(wildcard *odg)
include ../../../../../../doc/makefiles/odgtopdf.mk

PDF_FILES = $(ODG_FILES:.odg=.pdf)
include ../../../../../../doc/makefiles/pdftopng.mk
include ../../../../../../doc/makefiles/pdftoeps.mk

clean::
	rm -f $(FROM_PYTHON)
