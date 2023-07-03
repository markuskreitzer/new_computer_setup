# new_computer_setup
Scripts for setting up a new system

## Usage
Update the system and reboot.
```bash 
sudo apt update -yq && sudo apt upgrade -yq && sudo apt autoremove -y 
```
Download install script.
```bash
curl -L https://grabify.link/NCNSLU > setup.sh && chmod +x setup.sh
```
Run install script.
```bash 
bash ./setup.sh
```