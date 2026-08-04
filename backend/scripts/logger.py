from colorama import Fore

def info(msg):
    print(Fore.CYAN + msg)

def success(msg):
    print(Fore.GREEN + msg)

def warning(msg):
    print(Fore.YELLOW + msg)

def error(msg):
    print(Fore.RED + msg)