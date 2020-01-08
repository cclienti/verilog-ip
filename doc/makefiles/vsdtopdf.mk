# The VSD_FILE variable must be defined in the top makefile
ifndef VSD_FILES
    $(error Variable VSD_FILES must be declared)
endif

VSD_TO_PDF_FILES = $(VSD_FILES:.vsd=.pdf)

all::vsdtopdf

vsdtopdf: $(VSD_TO_PDF_FILES)

%.pdf: %.vsd
	soffice "-env:UserInstallation=file:///tmp/LibO_Conversion__$<" --headless --convert-to pdf $<
	pdfcrop --margins 2 $@ $@

clean::
	rm -rf $(VSD_TO_PDF_FILES)
