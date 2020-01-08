# The PDF_FILE variable must be defined in the top makefile
ifndef PDF_FILES
    $(error Variable PDF_FILES must be declared)
endif

PDF_TO_PNG_FILES = $(PDF_FILES:.pdf=.png)

all::pdftopng

pdftopng: $(PDF_TO_PNG_FILES)

%.png: %.pdf
	convert -bordercolor none -border 2 -density 200 $< $@

clean::
	rm -rf $(PDF_TO_PNG_FILES)
