.PHONY: all clean

all: jniwrap/cdefs.lua
	@$(MAKE) -C launcher all

clean:
	@$(MAKE) -C launcher clean
	$(RM) jniwrap/cdefs.lua

run: all
	env LD_LIBRARY_PATH=launcher java -cp launcher Test $(RUNARGS)

jniwrap/cdefs.lua: aosp-jni.h dumpcdefs.sh
	./dumpcdefs.sh $< > $@
