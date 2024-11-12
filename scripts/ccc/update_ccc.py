import subprocess

# Add this function after saving the files
def push_to_github():
    try:
        # Configure Git
        subprocess.run(["git", "config", "--global", "user.name", "GitHub Actions"], check=True)
        subprocess.run(["git", "config", "--global", "user.email", "actions@github.com"], check=True)
        
        # Add changes to git
        subprocess.run(["git", "add", "scripts/ccc/kxwl.txt", "scripts/ccc/kxwl.yaml"], check=True)
        
        # Commit the changes
        subprocess.run(["git", "commit", "-m", "Update kxwl files with recent content"], check=True)
        
        # Pull latest changes from remote to avoid conflicts
        subprocess.run(["git", "pull", "--rebase", "origin", "main"], check=True)
        
        # Push changes to GitHub
        subprocess.run(["git", "push", "origin", "main"], check=True)
        
        print("Changes pushed to GitHub successfully.")
    
    except subprocess.CalledProcessError as e:
        print("Failed to push changes:", e)

# Call the push function after fetching and saving files
if __name__ == "__main__":
    fetch_and_save_recent_files()
    push_to_github()
