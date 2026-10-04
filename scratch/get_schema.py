import urllib.request
import json

url = "https://vaagiltvlgomdmqevayv.supabase.co/rest/v1/?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZhYWdpbHR2bGdvbWRtcWV2YXl2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjEzNDcwNywiZXhwIjoyMDg3NzEwNzA3fQ.hwKPqpP0nldAD9UuqFO1NnHe9cmkhMmTlWLrN7LvV0M"

try:
    req = urllib.request.Request(url, headers={'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZhYWdpbHR2bGdvbWRtcWV2YXl2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjEzNDcwNywiZXhwIjoyMDg3NzEwNzA3fQ.hwKPqpP0nldAD9UuqFO1NnHe9cmkhMmTlWLrN7LvV0M'})
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        tables = []
        if 'definitions' in data:
            for table_name, table_def in data['definitions'].items():
                cols = list(table_def.get('properties', {}).keys())
                tables.append(f"Table: {table_name}")
                tables.append(f"Columns: {', '.join(cols)}")
                tables.append("---")
        
        with open('schema_output.txt', 'w') as f:
            f.write('\n'.join(tables))
        print("Schema saved to schema_output.txt")
except Exception as e:
    print("Error:", e)
