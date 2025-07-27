package.cpath = "./dep/?.dll;" .. package.cpath
local ffi = require("ffi")
local C = ffi.load("Kernel32")
--manual bit
local bit = {
  band = function(a, b) return a & b end,
  bor  = function(a, b) return a | b end,
  bxor = function(a, b) return a ~ b end,
  bnot = function(a)    return ~a end,
  lshift = function(a, b) return a << b end,
  rshift = function(a, b) return a >> b end,
}

local custom = require("requires.cli_h")
local colors = require("requires.ansicolors")

ffi.cdef[[
typedef void* HANDLE;
typedef unsigned long DWORD;
typedef unsigned short WORD;
typedef int BOOL;
typedef unsigned short wchar_t;
typedef wchar_t WCHAR;
typedef short SHORT;
typedef char CHAR;

typedef struct _COORD {
  SHORT X;
  SHORT Y;
} COORD;

typedef struct _KEY_EVENT_RECORD {
  BOOL bKeyDown;
  WORD wRepeatCount;
  WORD wVirtualKeyCode;
  WORD wVirtualScanCode;
  union {
    WCHAR UnicodeChar;
    CHAR AsciiChar;
  } uChar;
  DWORD dwControlKeyState;
} KEY_EVENT_RECORD;

typedef struct _INPUT_RECORD {
  WORD EventType;
  union {
    KEY_EVENT_RECORD KeyEvent;
  };
} INPUT_RECORD;

typedef struct _CONSOLE_SCREEN_BUFFER_INFO {
  COORD dwSize;
  COORD dwCursorPosition;
  WORD  wAttributes;
  COORD srWindow;
  COORD dwMaximumWindowSize;
} CONSOLE_SCREEN_BUFFER_INFO;

HANDLE GetStdHandle(DWORD nStdHandle);
BOOL GetConsoleMode(HANDLE hConsoleHandle, DWORD* lpMode);
BOOL SetConsoleMode(HANDLE hConsoleHandle, DWORD dwMode);
BOOL ReadConsoleInputA(HANDLE hConsoleInput, INPUT_RECORD* lpBuffer, DWORD nLength, DWORD* lpNumberOfEventsRead);
BOOL SetConsoleCursorPosition(HANDLE hConsoleOutput, COORD dwCursorPosition);
]]
local STD_INPUT_HANDLE  = -10
local STD_OUTPUT_HANDLE = -11
local ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
local VK_LEFT, VK_RIGHT = 0x25, 0x27
local VK_UP, VK_DOWN    = 0x26, 0x28
local VK_BACK           = 0x08
local VK_RETURN         = 0x0D
local LEFT_CTRL_PRESSED  = 0x0008
local RIGHT_CTRL_PRESSED = 0x0004
local hIn  = C.GetStdHandle(STD_INPUT_HANDLE)
local hOut = C.GetStdHandle(STD_OUTPUT_HANDLE)
local buffer = {""}
local cx, cy = 0, 0
local filename = nil
local mode = ffi.new("DWORD[1]")

if C.GetConsoleMode(hOut, mode) ~= 0 then
    mode[0] = bit.bor(mode[0], ENABLE_VIRTUAL_TERMINAL_PROCESSING)
    C.SetConsoleMode(hOut, mode[0])
end


local function draw()
    os.execute("cls")
    for i = 1, #buffer do
        print(buffer[i])
    end
    print("\n\n\x1b[;47;30;mCtrl - S: Save | Ctrl - Q: Quit | Arrow keys to move")
    if filename then
        print("File: " .. filename)
    else
        print("File: (unnamed)")
    end
end

local function clamp_cursor()
    if cy < 0 then cy = 0 end
    if cy >= #buffer then cy = #buffer - 1 end
    local line = buffer[cy + 1]
    if cx < 0 then cx = 0 end
    if cx > #line then cx = #line end
end

local function set_cursor(x, y)
    local coord = ffi.new("COORD")
    coord.X = x
    coord.Y = y
    C.SetConsoleCursorPosition(hOut, coord)
end

local function prompt_filename()
    io.write("\nEnter filename to save: ")
    local name = io.read()
    if name and #name > 0 then
        filename = name
    else
        print("Invalid filename, save cancelled.")
        filename = nil
    end
end

local function save_file()
    if not filename then
        prompt_filename()
        if not filename then return end
    end
    local f, err = io.open(filename, "w")
    if not f then
        print("Error saving file: " .. err)
        return
    end
    for _, line in ipairs(buffer) do
        f:write(line, "\n")
    end
    f:close()
    print("File saved as: " .. filename)
end

local function get_key()
    local buf = ffi.new("INPUT_RECORD[1]")
    local read = ffi.new("DWORD[1]")
    repeat
        C.ReadConsoleInputA(hIn, buf, 1, read)
    until buf[0].EventType == 1 and buf[0].KeyEvent.bKeyDown ~= 0

    local key = buf[0].KeyEvent.wVirtualKeyCode
    local char = buf[0].KeyEvent.uChar.UnicodeChar
    local mod = buf[0].KeyEvent.dwControlKeyState
    return key, char, mod
end

-- Main loop
draw()
set_cursor(cx, cy)

while true do
    local key, char, mod = get_key()
    local ctrl_down = bit.band(mod, LEFT_CTRL_PRESSED) ~= 0 or bit.band(mod, RIGHT_CTRL_PRESSED) ~= 0
    local line = buffer[cy + 1]

    if ctrl_down then
        if key == string.byte('Q') or key == 0x51 then
            break
        elseif key == string.byte('S') or key == 0x53 then
            save_file()
        elseif key == VK_LEFT then
            cx = cx - 1
        elseif key == VK_RIGHT then
            cx = cx + 1
        elseif key == VK_UP then
            cy = cy - 1
        elseif key == VK_DOWN then
            cy = cy + 1
        end
    else
        if key == VK_LEFT then
            cx = cx - 1
        elseif key == VK_RIGHT then
            cx = cx + 1
        elseif key == VK_UP then
            cy = cy - 1
        elseif key == VK_DOWN then
            cy = cy + 1
        elseif key == VK_BACK then
            if cx > 0 then
                buffer[cy + 1] = line:sub(1, cx - 1) .. line:sub(cx + 1)
                cx = cx - 1
            elseif cx == 0 and cy > 0 then
                local prev_line = buffer[cy]
                buffer[cy] = prev_line .. line
                table.remove(buffer, cy + 1)
                cy = cy - 1
                cx = #prev_line
            end
        elseif key == VK_RETURN then
            local new_line = line:sub(cx + 1)
            buffer[cy + 1] = line:sub(1, cx)
            table.insert(buffer, cy + 2, new_line)
            cy = cy + 1
            cx = 0
        elseif char ~= 0 then
            buffer[cy + 1] = line:sub(1, cx) .. string.char(char) .. line:sub(cx + 1)
            cx = cx + 1
        end
    end

    clamp_cursor()
    draw()
    set_cursor(cx, cy)
end
