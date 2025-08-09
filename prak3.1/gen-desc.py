import csv
import lorem

MAJORS_CNT = 10 ** 6

def main():
    with open('maj_desc.csv', 'w', newline='') as desc_csv:
        desc_fields = ['major_id', 'description']
        desc_writer = csv.DictWriter(desc_csv, fieldnames=desc_fields)
        for i in range(1, MAJORS_CNT + 1):
            if i % (MAJORS_CNT // 10) == 0:
                print(f'{i // (MAJORS_CNT // 10)}0%')
            desc_writer.writerow({
                'major_id': i,
                'description': lorem.get_sentence(count=(3,5))
            })


if __name__ == '__main__':
    main()
