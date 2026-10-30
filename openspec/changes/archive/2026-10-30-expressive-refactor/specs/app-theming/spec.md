# Spec Delta

## ADDED Requirements

### Requirement: Emphasized typography
Screen titles and the single most important text on each screen SHALL use emphasized styles (heavier weight on the Material 3 type scale); body text SHALL keep regular weight and honour the system font size.

#### Scenario: Large header
- **WHEN** a destination such as Chats or Settings opens
- **THEN** its title renders as an emphasized 36sp headline at the top of the content, left-aligned

### Requirement: Expressive navigation bar
The bottom navigation bar SHALL be 64dp tall (plus system insets) with a secondary-container pill indicator and labels always shown.

#### Scenario: Phone width
- **WHEN** the workspace shows on a phone
- **THEN** the navigation bar is 64dp tall and every destination shows its label
