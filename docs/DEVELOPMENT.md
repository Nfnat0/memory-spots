# Development Notes

## Success Criteria For The MVP

- A memory set can be created.
- Multiple photos can be added to a set.
- Themes can be created and switched.
- The same photo can show different notes depending on the selected theme.
- Notes can be added, edited, moved, and deleted on a photo.
- Review can run for a memory set and theme.
- Data persists after app relaunch.

## Main User Flows

1. Open the app and choose a memory set.
2. Select or create a theme.
3. Add place photos from the library or camera.
4. Open a photo and place notes.
5. Start review for the selected set and theme.

## Persistence Model

The app intentionally uses UUID references between SwiftData models rather than model relationships. This keeps the MVP simple and makes delete behavior explicit in the views.

Image files are managed separately by `ImageStore`.

## Review Behavior

Review is intentionally simple:

- Show the card front first.
- Reveal the answer on tap.
- Record one of three results.
- Advance to the next card.

There is no scheduling algorithm yet.

