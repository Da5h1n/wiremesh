import os
import shutil

for filename in os.listdir('.'):
    if filename.endswith('.lua'):
        txt_name = filename[:-4] + '.txt'
        shutil.copyfile(filename, txt_name)
        print(f"Saved {txt_name}")
