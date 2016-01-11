CC=clang
CFLAGS=-Wall -Wextra
CPPFLAGS=-I/usr/lib/jvm/java-8-openjdk/include -I/usr/lib/jvm/java-8-openjdk/include/linux -I/usr/include/lua5.1
LDADD=-lluajit-5.1
JAVA=java
JAVAC=javac
JAVAH=javah

.PHONY: all run clean

all: Test.class ExtraTest.class libTest.so

clean:
	$(RM) *.class *.so Test.h

run: all
	env LD_LIBRARY_PATH=. $(JAVA) -cp . Test

libTest.so: Test.c Test.h
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -fPIC -shared -o $@ $< $(LDADD)

%.class: %.java
	$(JAVAC) $<

Test.h: Test.class
	$(JAVAH) -cp . Test
