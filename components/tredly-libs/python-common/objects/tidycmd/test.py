from tidycmd import TidyCmd
# the following represents the following command being run within the shell:
# ifconfig | grep eth0 | awk '{ print $5 }

# create the object with the first command
tidyCmd = TidyCmd(['ifconfig'])
# first pipe
tidyCmd.appendPipe(['grep', 'eth0'])
# second pipe
tidyCmd.appendPipe(['awk', '{ print $5 }'])
# print out the command as a string
print(tidyCmd)

# run the command
print('RUN:')
print('------cut------')
print(tidyCmd.run())
print('------cut------')
print()
# print stdOut
print('STDOUT:')
print('------cut------')
print(tidyCmd.getStdOut())
print('------cut------')
print()

# print stdErr
print('STDERR:')
print('------cut------')
print(tidyCmd.getStdErr())
print('------cut------')
print()

tidyCmd.run()
# print the command again to prove nothing has changed
print(tidyCmd)
