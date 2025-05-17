import os
import time
import shutil
from config import CACHE_FOLDER, MAX_CACHE_SIZE_MB


def get_folder_size(path):
    total = 0
    for dirpath, _, filenames in os.walk(path):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            total += os.path.getsize(fp)
    return total / (1024 * 1024)


def enforce_cache_limit():
    while get_folder_size(CACHE_FOLDER) > MAX_CACHE_SIZE_MB:
        files = sorted(
            [os.path.join(dp, f)
             for dp, _, fn in os.walk(CACHE_FOLDER) for f in fn],
            key=lambda x: os.path.getatime(x)
        )
        if files:
            os.remove(files[0])
