# Vinyl App Design Assets

This directory is the repository location for visual source material used by the
application and future documentation website.

```text
design/
├── branding/      # Logo, palette, typography, and brand guidance
├── diagrams/      # Exported architecture and product diagrams
├── mockups/       # Approved high-fidelity concepts
├── screenshots/   # Current application screenshots by version or feature
└── wireframes/    # Early layout and interaction exploration
```

## Rules

- Keep source and exported files clearly named.
- Do not place runtime Flutter assets here unless they are also copied to and
  declared from the application asset location.
- Add the feature and version to screenshot names when useful.
- Avoid committing duplicate exports with names such as `final-final-2`.
- Record whether a mockup is current, superseded, or exploratory in the relevant
  folder README.

The current documentation package creates the organization but does not choose
one of the existing external mockups as the canonical design source.
