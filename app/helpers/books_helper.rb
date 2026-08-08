module BooksHelper
  # 3661 -> "1:01:01"; 125 -> "2:05"
  def format_hms(seconds)
    total = seconds.to_i
    hours, rem = total.divmod(3600)
    mins, secs = rem.divmod(60)
    hours.positive? ? format("%d:%02d:%02d", hours, mins, secs) : format("%d:%02d", mins, secs)
  end
end
