MAKEFLAGS := -j $(shell lscpu -x -p=CPU |grep -v ^\# |wc -l)

ODG_FILES = $(wildcard *odg)
include ../../../../resources/makefiles/odgtopdf.mk

PDF_FILES = $(ODG_FILES:.odg=.pdf)
include ../../../../resources/makefiles/pdftopng.mk
include ../../../../resources/makefiles/pdftoeps.mk

FROM_PYTHON = hynoc_path_versus_area.eps hynoc_path_versus_area.png \
		hynoc_routers_versus_area.eps hynoc_routers_versus_area.png

PYTHON_TARGET = $(firstword $(FROM_PYTHON))

all:: $(PYTHON_TARGET)

$(PYTHON_TARGET): hynoc_path_counting.py
	python3 $^

clean::
	rm -f $(FROM_PYTHON)
