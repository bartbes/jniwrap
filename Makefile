.PHONY: all clean

all:
	@$(MAKE) -C launcher all

clean:
	@$(MAKE) -C launcher clean

run: all
	env LD_LIBRARY_PATH=launcher java -cp launcher Test
