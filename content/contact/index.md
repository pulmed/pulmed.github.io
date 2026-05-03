---
title: Contact
date: 2022-10-24

type: landing

sections:
  - block: contact
    content:
      title: Contact
      text: |-
        For collaborations, student projects, and position inquiries, please get in touch by email.
      email: w.dekoning.1@erasmusmc.nl
      address:
        street: Doctor Molewaterplein 40
        city: Rotterdam
        postcode: '3015 GD'
        country: Netherlands
        country_code: NL
      coordinates:
        latitude: '51.9108'
        longitude: '4.4680'
      directions: Erasmus MC, Rotterdam.
      #contact_links:
      #  - icon: comments
      #    icon_pack: fas
      #    name: Discuss on Forum
      #    link: 'https://discourse.gohugo.io'
    
      # Automatically link email and phone or display as text?
      autolink: true
    
      # Email form provider
      form:
        provider: netlify
        formspree:
          id:
        netlify:
          # Enable CAPTCHA challenge to reduce spam?
          captcha: false
    design:
      columns: '1'

  - block: markdown
    content:
      title:
      subtitle: ''
      text:
    design:
      columns: '1'
      background:
        image: 
          filename: contact.jpg
          filters:
            brightness: 1
          parallax: false
          position: center
          size: cover
          text_color_light: true
      spacing:
        padding: ['20px', '0', '20px', '0']
      css_class: fullscreen
---
