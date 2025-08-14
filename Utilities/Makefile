CC=clang++

OPTS=-Wall -Werror -pedantic

LOPTS=-lobjc -framework Cocoa

TARGET=genColorHelp

all: $(TARGET)

$(TARGET): genColorHelp.o
	$(CC) $(LOPTS) -o $@ $^

genColorHelp.o : GenColorHelp.m
	$(CC) -c $(OPTS) $<

clean:
	rm -f $(TARGET) *.o table.*

