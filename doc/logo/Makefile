all: logo.done

logo.done: logo.py
	@echo "Generating logo png files"
	@./logo.py && touch logo.done

clean:
	@echo "Cleanning directory"
	@rm -rf *.done *.png
