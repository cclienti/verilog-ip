# Common Makefile parts
# Copyright (C) 2013 Christophe Clienti - All Rights Reserved

help::
	@echo "clean - remove generated files"

print-%:
	@echo $* = $($*)

eval-%:
	@echo $($*)

clean::
	rm -rf *~ *# ../src/*~ ../src/*# __pycache__
