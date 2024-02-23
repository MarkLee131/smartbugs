from collections import defaultdict

# Adjust these paths as necessary
input_file = './site-config/fungible_token.sbd'
output_file = './site-config/filtered_fungible_token.sbd'

# Function to extract the desired directory path from a full file path
def get_directory_path(file_path, depth=11):
    parts = file_path.split('/')
    # Adjust the depth to get the correct directory path
    directory_path = '/'.join(parts[:depth])
    return directory_path

# Count the occurrences of each directory
directory_counts = defaultdict(int)
# Store the full paths for each directory
directory_paths = defaultdict(list)

# Read the file paths and count them
with open(input_file, 'r') as f:
    for line in f:
        line = line.strip()
        directory = get_directory_path(line)
        directory_counts[directory] += 1
        directory_paths[directory].append(line)

# Filter and write the paths from directories with exactly one file
with open(output_file, 'w') as f:
    for directory, count in directory_counts.items():
        if count == 1:
            # Assuming there's exactly one, write it to the output file
            f.write(directory_paths[directory][0] + '\n')

print(f'Filtered paths have been written to {output_file}.')
