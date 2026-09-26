# text.rb : 글자 단위 분할과 자동 줄바꿈 (6단계에서 필요해져 먼저 만듦, 7단계가 쓴다)
# scripts/lua/rpg/text.lua 의 Ruby 판.
#
# 비트맵 폰트는 글자마다 폭이 다르므로 줄바꿈은 "몇 글자"가 아니라 "몇 픽셀"로
# 재야 한다. 폭 측정 함수(엔진의 Graphics.text_width)는 주입받는다. 그래야 이 모듈이
# 엔진 없이 단위 테스트로 검증된다 (09-testing.md 3.2절).
#
#   require "scripts/ruby/rpg/text"
#   lines = Rpg::Text.wrap("어서 오시게. 처음 보는 얼굴이군.", 360, ->(s) { Graphics.text_width(s) })
#
# Lua 판은 UTF-8 바이트 패턴으로 글자를 떼어 냈다. mruby 문자열은 글자 단위
# (chars, size, [], ord)라 그 자리를 chars 로 바꾸었다 (bytesize 가 바이트 수다).

module Rpg
  module Text
    # 문자열을 UTF-8 글자 배열로 나눈다 (한글 한 글자는 3바이트다).
    def self.chars(s)
      s.to_s.chars
    end

    # UTF-8 글자 수 (바이트 수가 아니다)
    def self.length(s)
      chars(s).size
    end

    # 앞에서 n글자만 잘라낸다 (타자 효과가 쓴다, 7단계).
    # n 이 실수여도 된다 (Lua 판처럼 n 이하의 글자까지 담는다).
    def self.sub(s, n)
      return "" if n <= 0
      chars(s)[0, n.floor].join
    end

    # 한글 조사 고르기. 앞말의 받침 유무로 갈린다.
    #
    #   Rpg::Text.particle("폭주", "을", "를")  # => "를"   (받침 없음)
    #   Rpg::Text.particle("도약", "을", "를")  # => "을"   (받침 ㄱ)
    #
    # "폭주을(를)"처럼 둘 다 적는 것은 글이 아니라 코드가 새어 나온 것이다.
    # 한글 음절은 U+AC00 부터 28개 종성 주기로 늘어서므로, (코드 - 0xAC00) % 28 이
    # 0이 아니면 받침이 있다. 한글이 아닌 글자로 끝나면 뒤엣것을 쓴다.
    def self.particle(word, with_jong, without_jong)
      last = chars(word).last
      return without_jong if last.nil?
      code = last.ord
      return without_jong if code < 0xAC00 || code > 0xD7A3
      (code - 0xAC00) % 28 != 0 ? with_jong : without_jong
    end

    # 앞말에 맞는 조사를 붙여 돌려준다 (Rpg::Text.with("도약", "을", "를") → "도약을")
    def self.with(word, with_jong, without_jong)
      word.to_s + particle(word, with_jong, without_jong)
    end

    # max_width 픽셀에 맞춰 줄을 나눈다.
    # 띄어쓰기에서 끊는 것을 우선하되, 한 낱말이 통째로 폭을 넘으면 글자에서 끊는다
    # (한국어는 띄어쓰기 없이 길게 이어지는 경우가 흔하다).
    # 원문의 개행(\n)은 그대로 유지한다.
    # measure  Proc (measure.call(text) -> 픽셀 폭)
    # 돌려주는 값 줄 문자열 배열
    def self.wrap(text, max_width, measure)
      raise ArgumentError, "text.wrap: 폭 측정 함수가 필요하다" unless measure.respond_to?(:call)
      lines = []

      # Lua 의 (text .. "\n"):gmatch("(.-)\n") 와 같다. 끝의 빈 조각 하나는 버린다.
      paragraphs = (text.to_s + "\n").split("\n", -1)
      paragraphs.pop

      paragraphs.each do |paragraph|
        if paragraph == ""
          lines.push("")
        else
          line = ""
          last_break = nil # 이번 줄에서 마지막으로 본 띄어쓰기 위치 (1부터 센 글자 위치)

          chars(paragraph).each do |c|
            candidate = line + c
            if line != "" && max_width > 0 && measure.call(candidate) > max_width
              if !last_break.nil? && last_break > 0
                # 띄어쓰기까지만 이번 줄에 남기고 나머지를 다음 줄로 넘긴다
                head = line[0, last_break - 1]
                tail = line[last_break, line.size - last_break] || ""
                lines.push(head)
                line = tail + c
              else
                lines.push(line)
                line = c
              end
              last_break = nil
              # 새 줄의 시작에 있는 띄어쓰기는 버린다
              line = "" if line == " "
            else
              line = candidate
            end
            if c == " "
              last_break = line.size # 글자 위치 (방금 붙인 공백). Lua 판은 바이트 위치였다
            end
          end

          lines.push(line)
        end
      end

      lines
    end
  end
end
