from math import radians, sin, cos, asin, sqrt


class GoogleService:
    def send_gmail_followup(self, to_email: str, subject: str, body: str):
        return {"provider": "gmail", "to": to_email, "subject": subject, "status": "queued"}

    def upload_drive_material(self, file_name: str):
        return {"provider": "drive", "file_name": file_name, "file_id": f"drive-{file_name}"}

    def export_to_sheets(self, report_name: str):
        return {"provider": "sheets", "report": report_name, "sheet_id": f"sheet-{report_name}"}

    def generate_doc(self, title: str):
        return {"provider": "docs", "title": title, "doc_id": f"doc-{title}"}

    def create_task(self, title: str):
        return {"provider": "tasks", "title": title, "task_id": f"task-{title}"}

    def sync_contacts(self):
        return {"provider": "contacts", "synced": True}

    def sync_calendar(self, brief_id: str):
        return {"provider": "calendar", "brief_id": brief_id, "synced": True}

    def haversine_miles(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        r = 3958.8
        d_lat = radians(lat2 - lat1)
        d_lon = radians(lon2 - lon1)
        a = sin(d_lat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(d_lon / 2) ** 2
        return 2 * r * asin(sqrt(a))
