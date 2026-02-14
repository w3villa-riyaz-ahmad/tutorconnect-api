# Seed file for development/testing
puts "Seeding database..."

# Create Admin
admin = User.find_or_create_by!(email: "admin@tutorconnect.com") do |u|
  u.first_name = "Admin"
  u.last_name = "User"
  u.password = "password123"
  u.role = :admin
  u.verified = true
end
puts "  ✓ Admin: #{admin.email}"

# Create sample teachers
3.times do |i|
  teacher = User.find_or_create_by!(email: "teacher#{i + 1}@tutorconnect.com") do |u|
    u.first_name = ["Alice", "Bob", "Carol"][i]
    u.last_name = "Teacher"
    u.password = "password123"
    u.role = :teacher
    u.verified = true
    u.tutor_status = :available
  end
  puts "  ✓ Teacher: #{teacher.email}"
end

# Create sample student
student = User.find_or_create_by!(email: "student@tutorconnect.com") do |u|
  u.first_name = "Test"
  u.last_name = "Student"
  u.password = "password123"
  u.role = :student
  u.verified = true
end
puts "  ✓ Student: #{student.email}"

puts "\nDone! Created #{User.count} users."
puts "\nTest accounts:"
puts "  Admin:   admin@tutorconnect.com / password123"
puts "  Teacher: teacher1@tutorconnect.com / password123"
puts "  Student: student@tutorconnect.com / password123"
