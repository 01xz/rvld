VERSION = 0.1.0
COMMIT_ID = $(shell git rev-list -1 HEAD)

CC = riscv64-linux-gnu-gcc

LD_BIN_DIR = ./zig-out/bin

BUILD_DIR = test

EXE = $(BUILD_DIR)/hello
OBJ = $(BUILD_DIR)/hello.o
SRC = $(BUILD_DIR)/hello.c

$(EXE): $(OBJ) build
	$(CC) -B$(LD_BIN_DIR) -static $< -o $@

$(OBJ): $(SRC)
	$(CC) -c $^ -o $@

build:
	@echo -e "\e[32mrun: zig build ...\e[0m"
	@zig build -Dversion="$(VERSION)-$(COMMIT_ID)"

clean:
	-rm -rf $(OBJ) $(EXE) zig-cache zig-out

.PHONY: build clean
