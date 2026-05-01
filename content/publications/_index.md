---
title: Publications & Theses
date: 2022-10-24
type: landing

sections:
  - block: markdown
    content:
      title: Publications & Theses
      text: |
        Research papers and theses are collected in one place and grouped below.
    design:
      columns: '1'

  - block: collection
    content:
      title: Latest Manuscripts
      text: ''
      count: 200
      filters:
        tag: manuscript
      offset: 0
      order: desc
      page_type: publications
    design:
      view: citation
      columns: '1'
      css_class: publications-showcase

  - block: markdown
    content:
      text: |
        <div class="collection-toggle-wrap">
          <button class="btn btn-outline-primary btn-sm js-expand-collection" data-target-class="publications-showcase" data-initial="5" data-more-label="Show more manuscripts" data-less-label="Show fewer manuscripts">Show more manuscripts</button>
        </div>
    design:
      columns: '1'

  - block: collection
    content:
      title: Thesis Gallery
      text: ''
      count: 200
      filters:
        tag: thesis
      offset: 0
      order: desc
      page_type: publications
    design:
      view: card
      columns: '3'
      css_class: thesis-showcase

  - block: markdown
    content:
      text: |
        <div class="collection-toggle-wrap">
          <button class="btn btn-outline-primary btn-sm js-expand-collection" data-target-class="thesis-showcase" data-initial="6" data-more-label="Show more theses" data-less-label="Show fewer theses">Show more theses</button>
        </div>
    design:
      columns: '1'
---
