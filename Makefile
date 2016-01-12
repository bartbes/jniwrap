.PHONY: all clean

all: jniwrap/cdefs.lua
	@$(MAKE) -C launcher all

clean:
	@$(MAKE) -C launcher clean
	$(RM) jniwrap/cdefs.lua

run: all
	env LD_LIBRARY_PATH=launcher java -cp launcher Test

jniwrap/cdefs.lua: dumpcdefs.sh
	./dumpcdefs.sh > $@
