import os
import sys

BACKEND_ROOT = os.path.dirname(os.path.dirname(__file__))
if BACKEND_ROOT not in sys.path:
    sys.path.insert(0, BACKEND_ROOT)

from mangum import Mangum

from openmeta.main import app

handler = Mangum(app)
