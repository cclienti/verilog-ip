ROOT_DIR  := $(shell git rev-parse --show-toplevel)/doc

MAKEFLAGS := -j $(shell lscpu -x -p=CPU |grep -v ^\# |wc -l)

ODG_FILES = $(wildcard *odg)
include $(ROOT_DIR)/makefiles/odgtopdf.mk

# PDF_FILES = $(ODG_FILES:.odg=.pdf)
# include $(ROOT_DIR)/makefiles/pdftopng.mk
