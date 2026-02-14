import os

# Define the path to your README
README_PATH = "../README.md"

# Define the "Evidence" for each task
# Key: The text in your README task list
# Value: The file or folder that proves it's done
TASKS = {
    "Initial Repository Architecture": ".git",
    "Ansible Playbook: Basic System Provisioning": "infrastructure/setup.yml",
    "SSH Handshake & Remote Control": "infrastructure/inventory.ini",
}

def sync_readme():
    if not os.path.exists(README_PATH):
        print(f"Error: {README_PATH} not found.")
        return

    with open(README_PATH, 'r') as f:
        lines = f.readlines()

    new_lines = []
    updated_count = 0

    for line in lines:
        updated_line = line
        for task_name, evidence_path in TASKS.items():
            # Check if this line contains our task name
            if task_name in line:
                # Path is relative to the project root
                full_path = os.path.join("..", evidence_path)
                
                if os.path.exists(full_path):
                    if "[ ]" in line:
                        updated_line = line.replace("[ ]", "[x]")
                        print(f"✅ Task Completed: {task_name}")
                        updated_count += 1
                else:
                    if "[x]" in line:
                        updated_line = line.replace("[x]", "[ ]")
                        print(f"⚠️ Task Reverted: {task_name} (Evidence missing)")
                        updated_count += 1
        
        new_lines.append(updated_line)

    with open(README_PATH, 'w') as f:
        f.writelines(new_lines)

    print(f"\nSync complete. {updated_count} status changes made.")

if __name__ == "__main__":
    sync_readme()
