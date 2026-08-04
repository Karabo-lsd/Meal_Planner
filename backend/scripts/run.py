import argparse

from .import_foods import run as import_foods


def main():
	parser = argparse.ArgumentParser(
		description="Import Spoonacular foods into Supabase."
	)
	parser.add_argument(
		"--yes",
		action="store_true",
		help="Run the import. Without this flag, the script exits without changing data.",
	)
	args = parser.parse_args()

	if not args.yes:
		print("No changes made. Re-run with --yes to import foods.")
		return

	import_foods()


if __name__ == "__main__":
	main()