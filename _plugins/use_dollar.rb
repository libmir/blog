module Jekyll
  class UseDollarGenerator < Generator
    safe true

    def generate(site)
      site.pages.each do |page|
        page.content = replace(page.content, page.ext)
      end

      site.posts.docs.each do |post|
        post.content = replace(post.content, ".md")
      end
    end

    def replace(content, ext)
      if ext == ".md"
        content.gsub!(/[$]([^$]*)[$]/, "{% latex %}\\1{% endlatex %}")
      end
      content
    end
  end
end
