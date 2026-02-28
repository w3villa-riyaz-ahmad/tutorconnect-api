namespace :users do
  desc "Create seed users (admin + teacher) for production"
  task seed_production: :environment do
    # Create Admin
    admin = User.find_or_initialize_by(email: "admin@tutorconnect.com")
    if admin.new_record?
      admin.assign_attributes(
        first_name: "Admin",
        last_name: "User",
        password: "Admin@123456",
        role: :admin,
        verified: true
      )
      admin.save!
      puts "✅ Admin created: admin@tutorconnect.com / Admin@123456"
    else
      puts "⏭️  Admin already exists"
    end

    # Create Teacher
    teacher = User.find_or_initialize_by(email: "teacher@tutorconnect.com")
    if teacher.new_record?
      teacher.assign_attributes(
        first_name: "Demo",
        last_name: "Teacher",
        password: "Teacher@123456",
        role: :teacher,
        verified: true,
        tutor_status: :available
      )
      teacher.save!
      puts "✅ Teacher created: teacher@tutorconnect.com / Teacher@123456"
    else
      puts "⏭️  Teacher already exists"
    end

    # Create Student
    student = User.find_or_initialize_by(email: "student@tutorconnect.com")
    if student.new_record?
      student.assign_attributes(
        first_name: "Demo",
        last_name: "Student",
        password: "Student@123456",
        role: :student,
        verified: true
      )
      student.save!
      puts "✅ Student created: student@tutorconnect.com / Student@123456"
    else
      puts "⏭️  Student already exists"
    end
  end
end
