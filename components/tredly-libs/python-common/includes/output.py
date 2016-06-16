# Output functions for colouring messages to CLI

# all codes as per http://misc.flogisoft.com/bash/tipcolorsandformatting
# Backgrounds
backgroundDefault = "\033[49m"
backgroundBlack = "\033[40m"
backgroundRed = "\033[41m"
backgroundGreen = "\033[42m"
backgroundYellow = "\033[43m"
backgroundBlue = "\033[44m"
backgroundMagenta = "\033[45m"
backgroundCyan = "\033[46m"
backgroundLightGray = "\033[47m"
backgroundDarkGray = "\033[100m"
backgroundLightRed = "\033[101m"
backgroundLightGreen = "\033[102m"
backgroundLightYellow = "\033[103m"
backgroundLightBlue = "\033[104m"
backgroundLightMagenta = "\033[105m"
backgroundLightCyan = "\033[106m"
backgroundWhite = "\033[107m"

# Formatting
formatBold = "\033[1m"
formatDim = "\033[2m"
formatUnderline = "\033[4m"
formatBlink = "\033[5m"
formatInvert = "\033[7m"
formatHidden = "\033[8m"
formatDefault = "\033[0m\033[39m"

# Colours
colourDefault = "\033[39m"
colourBlack = "\033[30m"
colourRed = "\033[31m"
colourOrange = "\033[38;5;202m"
colourGreen = "\033[32m"
colourYellow = "\033[33m"
colourBlue = "\033[34m"
colourMagenta = "\033[35m"
colourCyan = "\033[36m"
colourLightGray = "\033[37m"
colourDarkGray = "\033[90m"
colourLightRed = "\033[91m"
colourLightGreen = "\033[92m"
colourLightYellow = "\033[93m"
colourLightBlue = "\033[94m"
colourLightMagenta = "\033[95m"
colourLightCyan = "\033[96m"
colourWhite = "\033[97m"

# print out a header
def e_header(string):
    output = colourMagenta + formatBold
    
    # print out the equals signs
    for num in range(0,len(string)):
        output += "="
    
    output += "\n"
    
    # and now the string
    output += (string + colourDefault + formatDefault)
    output += "\n"
    
    # output it
    print(output)
    

# print out a note
def e_note(string):
    print(colourOrange + string + colourDefault)
    
# print a success message
def e_success(string = "Success"):
    print(colourGreen + string + colourDefault)

# print an error message
def e_error(string = "Failed"):
    print(colourRed + string + colourDefault)

# print a warning message
def e_warning(string):
    print(colourYellow + string + colourDefault)

# print an error message and exit
def exit_with_error(string, exitCode = 1):
    e_error(string)
    exit(exitCode)