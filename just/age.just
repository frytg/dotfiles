# create a new age encryption key into a given filename.
# writes <name>.txt + <name>pub.txt to ./tmp/ (gitignored).
[group('ENCRYPTION')]
create-age-key name="key":
	mkdir -p tmp
	age-keygen -o "tmp/{{ name }}.txt"
	just create-public-key "{{ name }}"
	just age-key-to-1password "{{ name }}"

# create a public key from a given age key
[confirm]
[group('ENCRYPTION')]
create-public-key name="key":
	age-keygen -y "tmp/{{ name }}.txt" > "tmp/{{ name }}pub.txt"

# create a 1password key from a given age key
[confirm]
[group('ENCRYPTION')]
age-key-to-1password name:
	op document create "./tmp/{{ name }}.txt" --title "Age key > {{ name }}" --tags "age" --file-name "{{ name }}.txt"
