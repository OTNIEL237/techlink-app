import shutil, os
src = r"C:\Users\Lenovo\.gemini\antigravity-ide\brain\3af507d5-f645-422b-824f-d9b968a7724f\specific_problem_bg_1781649415252.png"
dst = r"c:\Users\Lenovo\techlink-app\mobile\assets\images\specific_problem_bg.png"
if os.path.exists(src):
    shutil.copyfile(src, dst)
    print("File copied successfully")
else:
    print("Source file not found at:", src)
