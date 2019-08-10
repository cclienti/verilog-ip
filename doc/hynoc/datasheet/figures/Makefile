MAKEFLAGS := -j $(shell lscpu -x -p=CPU |grep -v ^\# |wc -l)

ODG_FILES = $(wildcard *odg)
include ../../../resources/makefiles/odgtopdf.mk

# PDF_FILES = $(ODG_FILES:.odg=.pdf)
# include ../../../resources/makefiles/pdftopng.mk
