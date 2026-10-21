# Smart Parking architecture visuals

These three SVGs summarize the project sources in Thai. Software, hardware-message paths, and technology names are shown in separate diagrams.

## Source map

| Diagram content | Source evidence |
| --- | --- |
| Flutter app and declared packages | `smart_parking_app/pubspec.yaml`; imports and API calls in `lib/main.dart`, `lib/services/api_service.dart`, and `lib/providers/parking_provider.dart` |
| App REST and WebSocket connections | `lib/services/api_service.dart`, `lib/providers/parking_provider.dart` |
| FastAPI, MQTT topics, device IDs, and gate sensor mappings | `smart_parking_backend/main.py` |
| PostgreSQL and SQLAlchemy | `smart_parking_backend/database.py`, `models.py`, and `requirements.txt` |
| Slot vision and its MQTT output | `smart_parking_photo_vision/slot_vision/slot_vision_service.py` and `requirements.txt` |

## Reading the hardware view

The arrows show software message directions described by the backend's MQTT subscriptions and publications. The project contains no controller firmware source, so the diagram does not claim that a particular physical wire or firmware behavior has been verified. The device IDs in the dashed group are listed by the backend; the IR gate roles shown there are also encoded in the backend's event handling.

The repository has more than one deployment configuration file, so these diagrams do not name an active cloud host. No payment provider is named in the application sources, so none is shown in the technology stack.
