import requests
import json
import pandas as pd
import sys
import os

def fetch_disease_targets(disease_id):
    """
    Fetch targets associated with a disease using Open Targets GraphQL API.
    disease_id can be an EFO ID (e.g., EFO_0000305) or a name search term.
    """
    url = "https://api.platform.opentargets.org/api/v4/graphql"
    
    # Check if ID looks like an EFO ID, otherwise search for it
    if not (disease_id.startswith("EFO_") or disease_id.startswith("MONDO_") or disease_id.startswith("ORPHA_")):
        print(f"Searching for disease: {disease_id}")
        query = """
        query Search($queryString: String!) {
          search(queryString: $queryString, entityNames: ["disease"], page: {index: 0, size: 1}) {
            hits {
              id
              name
            }
          }
        }
        """
        variables = {"queryString": disease_id}
        r = requests.post(url, json={"query": query, "variables": variables})
        data = r.json()
        hits = data.get("data", {}).get("search", {}).get("hits", [])
        if not hits:
            print(f"Error: Disease '{disease_id}' not found.")
            return []
        disease_id = hits[0]["id"]
        print(f"Found Disease ID: {disease_id} ({hits[0]['name']})")

    # Fetch targets
    print(f"Fetching targets for {disease_id}...")
    query = """
    query DiseaseTargets($efoId: String!) {
      disease(efoId: $efoId) {
        id
        name
        associatedTargets(page: {index: 0, size: 500}) {
          count
          rows {
            target {
              approvedSymbol
              approvedName
            }
            score
          }
        }
      }
    }
    """
    variables = {"efoId": disease_id}
    r = requests.post(url, json={"query": query, "variables": variables})
    
    if r.status_code != 200:
        print(f"Error: API request failed with status {r.status_code}")
        return []
        
    data = r.json()
    disease_data = data.get("data", {}).get("disease")
    if not disease_data:
        print(f"Error: No data found for disease {disease_id}")
        return []
        
    targets = []
    for row in disease_data.get("associatedTargets", {}).get("rows", []):
        targets.append({
            "symbol": row["target"]["approvedSymbol"],
            "name": row["target"]["approvedName"],
            "score": row["score"]
        })
        
    print(f"Successfully fetched {len(targets)} targets for {disease_data['name']}")
    return targets, disease_data['name']

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python fetch_disease_targets.py <disease_id_or_name> [output_path]")
        sys.exit(1)
        
    disease_input = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else "outputs"
    os.makedirs(out_dir, exist_ok=True)
    
    try:
        targets_list, disease_name = fetch_disease_targets(disease_input)
        if targets_list:
            df = pd.DataFrame(targets_list)
            
            output_file = os.path.join(out_dir, "disease_targets.csv")
            df.to_csv(output_file, index=False)
            print(f"Saved targets to {output_file}")
            
            # Save metadata for frontend
            with open(os.path.join(out_dir, "disease_info.json"), "w") as f:
                json.dump({"id": disease_input, "name": disease_name, "count": len(targets_list)}, f)
                
    except Exception as e:
        print(f"Error: {str(e)}")
        sys.exit(1)
