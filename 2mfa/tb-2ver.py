import sys
import os
import logging
from time import gmtime, strftime, time, sleep
import getopt
import pyotp
from typing import Optional, List, Tuple

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

# Configuration
DEFAULT_SECRET = os.getenv('TOTP_SECRET', 'default')
DEFAULT_SECRET_KEY = DEFAULT_SECRET.replace(" ", "")

# Global variables
DIGITS: str = ''
CURRENT_TIME: str = strftime('%Y%m%d%H%M%S', gmtime())

def generate_google_2fa_code(secret: str) -> str:
    """
    Generate a Google Authenticator 2FA code from the provided secret.
    
    Args:
        secret: Base32 encoded secret key
        
    Returns:
        str: 6-digit 2FA code
    """
    totp = pyotp.TOTP(secret)
    return totp.now()

def get_time_remaining() -> int:
    """Get the remaining seconds until the next 2FA code refresh."""
    return 30 - (int(time.time()) % 30)

def validate_2fa_code(digits: str, secret_key: str) -> bool:
    """
    Validate a 2FA code against the provided secret key.
    
    Args:
        digits: The 2FA code to validate
        secret_key: The base32 encoded secret key
        
    Returns:
        bool: True if the code is valid, False otherwise
    """
    return generate_google_2fa_code(secret_key) == digits

def usage(exit_value: int = 2) -> None:
    """Display script usage information and exit."""
    print("""
Usage: python tb.py [options]

Options:
  -h, --help          Show this help message and exit
  -d, --digit CODE    The 2FA code to validate

Example:
  python tb.py -d 123456
""")
    sys.exit(exit_value)

def main() -> None:
    """Main function to validate a 2FA code."""
    try:
        print(f'Input digits: {DIGITS}')
        print('Validating against Google Authenticator 2FA')
        
        if validate_2fa_code(DIGITS, DEFAULT_SECRET_KEY):
            print('✅ Valid code!')
            sleep(3)
            sys.exit(0)
        else:
            print('❌ Invalid code!')
            sleep(3)
            sys.exit(1)
            
    except Exception as e:
        logging.error(f'An error occurred: {str(e)}')
        sys.exit(1)

if __name__ == '__main__':
    try:
        opts, args = getopt.getopt(sys.argv[1:], "hd:", ["help", "digit="])
        
        for opt, arg in opts:
            if opt in ('-h', '--help'):
                usage(0)
            elif opt in ('-d', '--digit'):
                DIGITS = arg.strip()
                
        if not DIGITS:
            logging.error('No 2FA code provided')
            usage(2)
            
        main()
        
    except getopt.GetoptError as e:
        logging.error(f'Invalid command line arguments: {str(e)}')
        usage(2)
    except Exception as e:
        logging.error(f'Unexpected error: {str(e)}')
        sys.exit(1)

