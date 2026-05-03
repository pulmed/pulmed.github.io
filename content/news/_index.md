---
title: News
date: 2026-05-03
type: landing

sections:
  - block: markdown
    content:
      title: News
      text: |
        Latest updates from the group, including newly added research, publications, software, collaborations, and posts.
    design:
      columns: '1'

  - block: collection
    content:
      title: Latest Updates
      text: ''
      count: 30
      filters:
        folders:
          - post
          - publications
          - research
          - projects
          - software
          - collaborations
          - join-us
      offset: 0
      order: desc
    design:
      view: card
      columns: '1'
---
