import requests
from bs4 import BeautifulSoup

import argparse

URL = "https://en.wikipedia.org/wiki/List_of_reported_UFO_sightings"

parser = argparse.ArgumentParser()
parser.add_argument("-p", "--wiki_page", help="Give a wiki page to scrape", default=URL)
args = parser.parse_args()

resp = requests.get(
    args.wiki_page,
    headers={"User-Agent": "Mozilla/5.0"},
    timeout=30,
)
res = resp.text
soup = BeautifulSoup(res, "lxml")



tables = soup.find_all("table", class_="wikitable")
if not tables:
    print("No table with class='wikitable' found.")
    print("HTTP status:", resp.status_code)
    print("Final URL:", resp.url)
    print("Content-Type:", resp.headers.get("content-type"))
    print("Body prefix:", res[:200].replace("\n", " "))
    print("First 5 tables' classes:", [t.get("class") for t in soup.find_all("table")[:5]])
    raise SystemExit(1)

matched_any_table = False
for table in tables:
    header_row = table.find("tr")
    if header_row is None:
        continue

    headers = [th.get_text(" ", strip=True) for th in header_row.find_all("th")]
    if "Description" not in headers:
        continue

    matched_any_table = True
    description_idx = headers.index("Description")
    for row in table.find_all("tr")[1:]:
        cells = row.find_all(["th", "td"])
        if len(cells) <= description_idx:
            continue
        description = cells[description_idx].get_text(" ", strip=True)
        if description:
            print(description)

if not matched_any_table:
    raise SystemExit("No wikitable contained a 'Description' column.")