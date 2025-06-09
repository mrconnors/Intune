
## Introduction in Custom OOBE

**CustomOOBE** is a thing you can use to communicate important information to your users before they see the Desktop. This could be onboarding information, internal company rules, or rules for using your internal software

**CustomOOBE** is a powershell script that modifies the system files of the *Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy* application, which is responsible for rendering all OOBE screens in Windows.

**Please note that you take responsibility for modifying the system files when you decide to run this script! The script was tested on Windows 11 10.0.26100.1742 and Windows 11 10.0.26100.4061. I strongly recommend that you test it in a test environment before implementing it in your technology preparation flow!**

I spent a lot of time studying the [OOBE scheme](https://mtniehaus.github.io/Misc/OOBE.html) that [Michael Niehaus](https://oofhours.com/author/mtniehaus) kindly put together. The epiphany came to me, oddly enough, after watching a video about hacking OOBE screens on the [Enderman](https://www.youtube.com/@Endermanch) YouTube channel.

## Usage

In order to use **CustomOOBE**, you need to upload files from the CustomOOBE folder

Next, you need to fill in the configuration.json file with the information you need:
There are 10 blocks in the file, each block has three values:
- **Title** - Screen title. If there is no title, the block is skipped
- **Content** - The main text of the block
- **Lottie** - the full name of the animation file. You can see the standard animation files at `C:\Windows\SystemApps\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy\images`.

Next, if necessary, upload your animation to the Lottie folder. The name does not matter, the main thing is that you correctly fill in this name in configuration.json

Next, create an **.intunewin** archive from these files. To test the installation, use the **detection.ps1** file, if desired, you can use the requirement script, it checks whether this script has been installed before.

**Attention! When testing, create a backup copy of navigation.json. Before re-running the script, restore the default navigation.json. The script does not know that you have already modified navigation.json, and will simply add new lines over the old ones.**

I recommend installing the script as a **Win32** application, it is better to use powershell x64 to run it. Here is the launch line I used:
```
%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -noprofile -executionpolicy bypass -windowstyle hidden -File .\CustomOOBEv2.3_prod.ps1
```
In some places I used **ChatGPT** to write the code, so the request for the code is not too sweary

I really hope that my work will encourage someone to further explore the OOBE labyrinths. I had too little time for research. But I managed to get a fully working version, with convenient text and animation changes at any time!
##  Description

#### Understanding Windows OOBE
So, first we need to understand how OOBE works. There is a file **navigation.json** which is located in `C:\Windows\SystemApps\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy\data\prod`. It is responsible for the logic and sequence of the OOBE screens that **Michael Niehaus** talked about. The file has many entry points, a system process (I haven't figured out which one yet) launches one of the entry points in navigation.json, then in this entry point there are a certain number of blocks, there is the first block and the last one. These blocks have properties:

- Block name
- Block ID
- Name of the animation file that will be played
- Path to the **name.html** file from which the text is taken
- ID of the block that comes next if there are no errors
- ID of the block that will be next if the user presses the Cancel button
- ID of the block that will be next if the loading of the current block is interrupted
- The visibility parameter, I still don’t understand why it is needed

Now that we have figured out what the block looks like, let’s figure out the files that are responsible for this block. In point 4, I indicated that there is a link to a certain **name.html** file. All files are located in the directory `C:\Windows\SystemApps\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy\webapps\inclusiveOobe\view`

The file consists of html code and links to **name-page.js** and **name-vm.js** files that form the content of the page depending on the localization, position and formatting of the text, write to the registry, read registry values, create files and much more. They are located in `C:\Windows\SystemApps\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy\webapps\inclusiveOobe\js`. For each page, there are two files **name-vm.js** and **name-page.js**

Also in the directory `C:\Windows\SystemApps\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy\images` there are animation files, they look like **nameLottie.json**. You can open any of them in **LottieViewer** software, and by analogy with them create your own animation file, or use existing ones.

So, we know that for one screen to work we need the following files:
- **name.html**
- **name-page.js**
- **name-vm.js**
- **nameLottie.json**

We also know that initially in **navigation.json** we specify only animation files and html. And already in the html itself we specify the file name-page.js In the file **name-page.js** we specify our **name.html** file back, and the file **name-vm.js**. And so on for each page.

I had two ways, to understand the logic of building pages, and create **name.html** and **name-page.js**, **name-vm.js** files from scratch. Or take one of the pages as a template, and use it. I will not hide that I tried the first option, and nothing worked out for me. Therefore, I began to look for a suitable template for myself.

It is worth paying attention that all (almost all) pages in OOBE are tightly tied to js scripts, and appear only after checks, and it was not possible to call them just like that. In the end, I settled on the **networklosserror page**, the task of which is in fact to display text about the loss of the Internet connection, before appearing it does not check anything, because it is called by an error on one of the previous pages.

As a result, I got one working page, I set the text directly in html, used my formatting, in vm.js I wrote the logic of the timer on the button. The question arose for me, between which blocks to insert my page. After several experiments, I found out that the **Windows Hello** installation pass is in the **navigation.json** file in **NTHAADORMDM**. And when I inserted my block between the **MDMProgressRefactored** and **AADHello blocks**, everything worked like a charm!

The logic is as follows. If the user who logs in does not have a registered **Windows Hello** certificate (no PIN code), then the **NTHAADORMDM** pass is launched, which in turn launches my custom pages, and after them the standard **Windows Hello** screens are launched
How the script works:
- For system locations where **name.html**, **navigation.json**, **name-page.js**, **name-vm.js** and **Lottie.json** are stored, the owner is changed to the **Administrators group** and full rights are granted for this group
- Logging starts in `C:\ProgramData\CustomOOBE\CustomOOBE.log`
- Animations are copied from the Lottie folder to the system location (you can put your own animations there)
- The **configuration.json** file is read. If the **Title** of the block is empty, this block **is skipped**.
- The **name.html**, **name-page.js**, **name-vm.js** files are created for each page from the **configuration.json** file.
- The **navigation.json** file is parsed, the script finds the **NTHAADORMDM** gap in it, then finds the **MDMProgressRefactored** and **AADHello** blocks in this gap. Between them, observing the json punctuation, and according to the information from **configuration.json**, page blocks are created.
- If successful, an entry is created in the registry `HKLM:\Software\CustomOOBE\CustomOOBEv2.3Complete` with the value of the current timestamp.